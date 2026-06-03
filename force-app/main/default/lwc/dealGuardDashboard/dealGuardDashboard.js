import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuest from '@salesforce/user/isGuest';
import DEALGUARD_LOGO from '@salesforce/resourceUrl/dealGuardLogo';
import getDeals from '@salesforce/apex/DealGuardController.getDeals';
import createDeal from '@salesforce/apex/DealGuardController.createDeal';
import updateDecision from '@salesforce/apex/DealGuardController.updateDecision';
import seedDemoData from '@salesforce/apex/DealGuardController.seedDemoData';

const DEFAULT_FORM = {
    accountName: '',
    salesRepName: '',
    region: 'West',
    customerTier: 'Growth',
    dealStage: 'Negotiation',
    dealAmount: 75000,
    deliveryCost: 42000,
    discountPercent: 14,
    discountReason: ''
};

const ROLES = ['Sales Manager', 'Regional Director', 'Finance Controller'];
const FILTERS = ['All', 'Pending', 'Approved', 'Rejected'];
const APPROVER_ROLES = ['Auto Approved', ...ROLES];

export default class DealGuardDashboard extends LightningElement {
    @track deals = [];
    @track form = { ...DEFAULT_FORM };
    selectedId;
    selectedRole = 'Sales Manager';
    activeFilter = 'All';
    searchKey = '';
    decisionNote = '';
    isLoading = false;

    regions = ['North', 'South', 'West', 'East', 'Central'];
    tiers = ['Standard', 'Growth', 'Strategic'];
    stages = ['Qualification', 'Negotiation', 'Procurement', 'Legal Review'];
    roleOptions = ROLES;

    connectedCallback() {
        this.loadDeals();
    }

    get isPublicVisitor() {
        return isGuest;
    }

    get logoUrl() {
        return DEALGUARD_LOGO;
    }

    async loadDeals() {
        this.isLoading = true;
        try {
            const records = await getDeals();
            this.deals = records || [];
            if (!this.deals.length && !this.isPublicVisitor) {
                await seedDemoData();
                this.deals = await getDeals();
            }
            if (!this.selectedId && this.deals.length) {
                const pending = this.deals.find((deal) => deal.approvalStatus === 'Pending');
                this.selectedId = (pending || this.deals[0]).id;
            }
            if (this.selectedId && !this.deals.some((deal) => deal.id === this.selectedId)) {
                this.selectedId = this.deals.length ? this.deals[0].id : undefined;
            }
        } catch (error) {
            this.showError('Unable to load DealGuard records', error);
        } finally {
            this.isLoading = false;
        }
    }

    get filterOptions() {
        return FILTERS.map((filter) => ({
            label: filter,
            value: filter,
            className: `segment ${this.activeFilter === filter ? 'active' : ''}`
        }));
    }

    get dealRows() {
        const query = this.searchKey.trim().toLowerCase();
        return this.deals
            .filter((deal) => {
                const matchesFilter = this.activeFilter === 'All' || deal.approvalStatus === this.activeFilter;
                const haystack = `${deal.name} ${deal.accountName} ${deal.salesRepName} ${deal.region}`.toLowerCase();
                return matchesFilter && haystack.includes(query);
            })
            .map((deal) => this.decorateDeal(deal));
    }

    get hasDeals() {
        return this.dealRows.length > 0;
    }

    get selectedDeal() {
        return this.deals.find((deal) => deal.id === this.selectedId) || this.deals[0];
    }

    get selectedDealView() {
        return this.selectedDeal ? this.decorateDeal(this.selectedDeal) : null;
    }

    get metrics() {
        const pending = this.deals.filter((deal) => deal.approvalStatus === 'Pending');
        const approved = this.deals.filter((deal) => deal.approvalStatus === 'Approved');
        const exposure = this.deals.reduce((sum, deal) => sum + Number(deal.discountValue || 0), 0);
        const risky = this.deals.filter((deal) => deal.riskLevel === 'High');
        const averageDiscount = this.deals.length
            ? this.deals.reduce((sum, deal) => sum + Number(deal.discountPercent || 0), 0) / this.deals.length
            : 0;

        return {
            pipeline: this.formatMoney(pending.reduce((sum, deal) => sum + Number(deal.finalPrice || 0), 0)),
            pipelineSub: `${pending.length} active request${pending.length === 1 ? '' : 's'}`,
            approved: this.formatMoney(approved.reduce((sum, deal) => sum + Number(deal.finalPrice || 0), 0)),
            approvedSub: `${approved.length} won-ready deal${approved.length === 1 ? '' : 's'}`,
            exposure: this.formatMoney(exposure),
            exposureSub: `${averageDiscount.toFixed(1)}% average discount`,
            risk: risky.length
        };
    }

    get preview() {
        const amount = Number(this.form.dealAmount || 0);
        const cost = Number(this.form.deliveryCost || 0);
        const discount = Number(this.form.discountPercent || 0);
        const finalPrice = amount * (1 - discount / 100);
        const discountValue = amount * (discount / 100);
        const margin = finalPrice ? ((finalPrice - cost) / finalPrice) * 100 : 0;
        const policy = this.calculatePolicy(amount, cost, discount, this.form.customerTier);

        return {
            finalPrice: this.formatMoney(finalPrice),
            discountValue: this.formatMoney(discountValue),
            marginLabel: `${Math.round(margin * 10) / 10}%`,
            discountLabel: `${discount}%`,
            requiredApprover: policy.requiredApprover
        };
    }

    get approvalPath() {
        const selected = this.selectedDealView;
        if (!selected) {
            return [];
        }

        let steps = ['Auto Approved'];
        if (selected.requiredApprover === 'Sales Manager') {
            steps = ['Sales Manager'];
        } else if (selected.requiredApprover === 'Regional Director') {
            steps = ['Sales Manager', 'Regional Director'];
        } else if (selected.requiredApprover === 'Finance Controller') {
            steps = ['Sales Manager', 'Regional Director', 'Finance Controller'];
        }

        return steps.map((step, index) => ({
            label: step,
            index: index + 1,
            type: step === 'Auto Approved' ? 'System' : 'User',
            className: `path-step ${step === selected.requiredApprover ? 'current' : ''}`
        }));
    }

    get decisionDisabled() {
        const selected = this.selectedDealView;
        return this.isPublicVisitor || !selected || selected.approvalStatus !== 'Pending' || !this.canRoleDecide(this.selectedRole, selected.requiredApprover);
    }

    get decisionPlaceholder() {
        const selected = this.selectedDealView;
        if (!selected) {
            return 'Select a deal request.';
        }
        if (selected.approvalStatus !== 'Pending') {
            return 'This deal already has a final decision.';
        }
        if (!this.canRoleDecide(this.selectedRole, selected.requiredApprover)) {
            return `${selected.requiredApprover} or higher must decide this request.`;
        }
        return 'Add business justification or rejection reason';
    }

    get chartRows() {
        const counts = this.deals.reduce((map, deal) => {
            const approver = deal.requiredApprover || 'Auto Approved';
            map[approver] = (map[approver] || 0) + 1;
            return map;
        }, {});
        const max = Math.max(1, ...Object.values(counts));

        return APPROVER_ROLES.map((role) => {
            const count = counts[role] || 0;
            const width = count ? Math.max(8, Math.round((count / max) * 100)) : 0;
            return {
                label: role,
                count,
                style: `width: ${width}%`
            };
        });
    }

    get timelineItems() {
        return this.deals
            .flatMap((deal) =>
                (deal.activity || []).map((entry, index) => ({
                    key: `${deal.id}-${index}`,
                    text: entry,
                    dealLabel: `${deal.name} | ${deal.accountName}`
                }))
            )
            .slice(0, 8);
    }

    handleFilterChange(event) {
        this.activeFilter = event.currentTarget.dataset.filter;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleSelectDeal(event) {
        this.selectedId = event.currentTarget.dataset.id;
        this.decisionNote = '';
    }

    handleRoleChange(event) {
        this.selectedRole = event.target.value;
    }

    handleFormInput(event) {
        const { name, value, type } = event.target;
        this.form = {
            ...this.form,
            [name]: type === 'number' || type === 'range' ? Number(value) : value
        };
    }

    handleDecisionNoteChange(event) {
        this.decisionNote = event.target.value;
    }

    async handleSubmit(event) {
        event.preventDefault();

        if (this.isPublicVisitor) {
            return;
        }

        if (Number(this.form.discountPercent) > 10 && !this.form.discountReason.trim()) {
            this.showToast('Discount reason required', 'Add a reason when discount is above 10%.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const created = await createDeal({ input: this.toInputPayload() });
            await this.loadDeals();
            this.selectedId = created.id;
            this.form = { ...DEFAULT_FORM };
            this.showToast('Request submitted', `${created.name} was created in Salesforce.`, 'success');
        } catch (error) {
            this.showError('Unable to submit request', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDecision(event) {
        if (this.isPublicVisitor) {
            return;
        }

        const status = event.currentTarget.dataset.status;
        const selected = this.selectedDealView;
        if (!selected) {
            return;
        }

        this.isLoading = true;
        try {
            const updated = await updateDecision({
                dealId: selected.id,
                status,
                note: this.decisionNote,
                actorRole: this.selectedRole
            });
            await this.loadDeals();
            this.selectedId = updated.id;
            this.decisionNote = '';
            this.showToast('Decision saved', `${updated.name} ${status.toLowerCase()} by ${this.selectedRole}.`, 'success');
        } catch (error) {
            this.showError('Unable to save decision', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSeedDemo() {
        if (this.isPublicVisitor) {
            return;
        }

        this.isLoading = true;
        try {
            const inserted = await seedDemoData();
            await this.loadDeals();
            this.showToast('Demo data ready', inserted ? `${inserted} records created.` : 'Your org already has DealGuard records.', 'success');
        } catch (error) {
            this.showError('Unable to seed demo data', error);
        } finally {
            this.isLoading = false;
        }
    }

    decorateDeal(deal) {
        const isSelected = deal.id === this.selectedId;
        return {
            ...deal,
            rowClass: `deal-row ${isSelected ? 'selected' : ''}`,
            statusClass: `status-pill status-${deal.approvalStatus}`,
            riskClass: `risk-pill risk-${deal.riskLevel}`,
            riskLabel: `${deal.riskLevel} risk`,
            finalPriceLabel: this.formatMoney(deal.finalPrice),
            discountValueLabel: this.formatMoney(deal.discountValue),
            discountLabel: `${deal.discountPercent}%`,
            marginLabel: `${deal.marginPercent}%`
        };
    }

    toInputPayload() {
        return {
            accountName: this.form.accountName,
            salesRepName: this.form.salesRepName,
            region: this.form.region,
            customerTier: this.form.customerTier,
            dealStage: this.form.dealStage,
            dealAmount: Number(this.form.dealAmount || 0),
            deliveryCost: Number(this.form.deliveryCost || 0),
            discountPercent: Number(this.form.discountPercent || 0),
            discountReason: this.form.discountReason
        };
    }

    calculatePolicy(amount, cost, discount, tier) {
        const finalPrice = amount * (1 - discount / 100);
        const margin = finalPrice ? ((finalPrice - cost) / finalPrice) * 100 : 0;

        if (margin < 18 || discount >= 31) {
            return { requiredApprover: 'Finance Controller' };
        }
        if (discount >= 21 || amount >= 150000 || (tier === 'Strategic' && discount > 15)) {
            return { requiredApprover: 'Regional Director' };
        }
        if (discount >= 11) {
            return { requiredApprover: 'Sales Manager' };
        }
        return { requiredApprover: 'Auto Approved' };
    }

    canRoleDecide(currentRole, requiredRole) {
        const hierarchy = { 'Sales Manager': 1, 'Regional Director': 2, 'Finance Controller': 3 };
        const currentRank = hierarchy[currentRole];
        const requiredRank = hierarchy[requiredRole];
        if (currentRank == null || requiredRank == null) return false;
        return currentRank >= requiredRank;
    }

    formatMoney(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(Number(value || 0));
    }

    showError(title, error) {
        const message = error?.body?.message || error?.message || 'Unexpected Salesforce error.';
        this.showToast(title, message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
